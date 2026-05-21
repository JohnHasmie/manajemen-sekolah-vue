// Bottom sheet for manually recording a student payment.
//
// The sheet owns its own file-picker flow now — earlier versions popped the
// form sheet first and tried to re-show it after the system picker returned,
// but the State was already disposed by the pop, so `mounted == false` and
// the form never came back. Admins ended up dropped back on the report
// screen with no upload and no confirmation.
//
// Current flow:
//   * Tap "Pilih File"  → opens a small "Pilih jenis file" sheet ABOVE the
//                          form (no pop, so the form stays mounted).
//   * Pick Image/PDF   → opens the OS picker; on return we setState locally
//                          to surface the chosen file inside the form.
//   * Tap "Simpan"     → invokes [onSave], which uploads + shows the success
//                          snackbar via the parent's payment mixin.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/bill_info_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/payment_form_mixin.dart';

/// Shows a bottom sheet for manually recording a payment.
///
/// The sheet owns its own selectedFile state — callers no longer pass an
/// `onPickFile` callback. The file picker is invoked from inside the sheet
/// without dismissing the form, so the user keeps their context.
///
/// `onSave` is awaited and must return `true` if the payment persisted
/// successfully — in that case the sheet pops itself. Returning `false`
/// (or throwing) leaves the sheet open so the admin can retry without
/// re-typing.
void showManualPaymentSheet({
  required BuildContext context,
  required dynamic bill,
  required Color primaryColor,
  required String Function(dynamic) formatCurrency,
  required Future<bool> Function({
    required String paymentMethod,
    required double amount,
    required String date,
    File? file,
  })
  onSave,
  required TextEditingController paymentMethodController,
  required TextEditingController amountController,
  required TextEditingController paymentDateController,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ManualPaymentSheetContent(
      bill: bill,
      primaryColor: primaryColor,
      formatCurrency: formatCurrency,
      onSave: onSave,
      paymentMethodController: paymentMethodController,
      amountController: amountController,
      paymentDateController: paymentDateController,
    ),
  );
}

/// Internal stateful content widget for the manual payment sheet.
class _ManualPaymentSheetContent extends StatefulWidget {
  final dynamic bill;
  final Color primaryColor;
  final String Function(dynamic) formatCurrency;
  final Future<bool> Function({
    required String paymentMethod,
    required double amount,
    required String date,
    File? file,
  })
  onSave;
  final TextEditingController paymentMethodController;
  final TextEditingController amountController;
  final TextEditingController paymentDateController;

  const _ManualPaymentSheetContent({
    required this.bill,
    required this.primaryColor,
    required this.formatCurrency,
    required this.onSave,
    required this.paymentMethodController,
    required this.amountController,
    required this.paymentDateController,
  });

  @override
  State<_ManualPaymentSheetContent> createState() =>
      _ManualPaymentSheetContentState();
}

class _ManualPaymentSheetContentState extends State<_ManualPaymentSheetContent>
    with BillInfoMixin, PaymentFormMixin {
  File? _currentFile;
  bool _isPicking = false;
  bool _isSubmitting = false;

  @override
  dynamic get bill => widget.bill;
  @override
  Color get primaryColor => widget.primaryColor;
  @override
  String Function(dynamic) get formatCurrency => widget.formatCurrency;
  @override
  TextEditingController get paymentMethodController =>
      widget.paymentMethodController;
  @override
  TextEditingController get amountController => widget.amountController;
  @override
  TextEditingController get paymentDateController =>
      widget.paymentDateController;

  /// Opens the file-type selector ABOVE the form sheet, then routes to the
  /// system gallery / camera / file picker. Never pops the form — when the
  /// OS picker returns, we just setState locally so the form re-renders with
  /// the file selected.
  Future<void> _handlePickFile() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final action = await AppBottomSheet.show<String>(
        context: context,
        title: AppLocalizations.chooseFileType.tr,
        subtitle: AppLocalizations.uploadPaymentProof.tr,
        icon: Icons.upload_file_rounded,
        primaryColor: widget.primaryColor,
        content: Builder(
          builder: (sheetContext) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.image_outlined,
                  color: widget.primaryColor,
                ),
                title: Text(AppLocalizations.imageCameraGallery.tr),
                onTap: () => AppNavigator.pop(sheetContext, 'image'),
              ),
              ListTile(
                leading: Icon(
                  Icons.picture_as_pdf_outlined,
                  color: widget.primaryColor,
                ),
                title: Text(AppLocalizations.pdfDocument.tr),
                onTap: () => AppNavigator.pop(sheetContext, 'pdf'),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      if (action == 'image') {
        await _pickImage();
      } else if (action == 'pdf') {
        await _pickPdf();
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Gagal memilih file: $e');
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickImage() async {
    final source = await AppBottomSheet.show<ImageSource>(
      context: context,
      title: AppLocalizations.chooseSource.tr,
      subtitle: AppLocalizations.chooseImageSource.tr,
      icon: Icons.camera_alt_rounded,
      primaryColor: widget.primaryColor,
      content: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: widget.primaryColor,
              ),
              title: Text(AppLocalizations.gallery.tr),
              onTap: () =>
                  AppNavigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt_outlined,
                color: widget.primaryColor,
              ),
              title: Text(AppLocalizations.camera.tr),
              onTap: () =>
                  AppNavigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;

    // No snackbar — the green file-selected card inside the sheet
    // already shows the filename + "Gambar JPEG" label. The duplicate
    // snackbar was redundant noise.
    setState(() => _currentFile = File(file.path));
  }

  Future<void> _pickPdf() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (!mounted) return;
    final path = result?.files.single.path;
    if (result == null || path == null) return;

    // Same as _pickImage: skip the duplicate confirmation snackbar — the
    // green file-selected card inside the sheet is the canonical UI for
    // "you picked this PDF".
    setState(() => _currentFile = File(path));
  }

  String _getFileTypeText(String filePath) {
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

  Future<void> _handleSave() async {
    if (_isSubmitting) return;
    final paymentMethod = paymentMethodController.text.trim();
    final amountText = amountController.text.trim();
    final date = paymentDateController.text.trim();

    if (paymentMethod.isEmpty || amountText.isEmpty || date.isEmpty) {
      SnackBarUtils.showWarning(
        context,
        'Mohon lengkapi metode, jumlah, dan tanggal pembayaran.',
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null) {
      SnackBarUtils.showWarning(context, 'Format jumlah pembayaran tidak valid.');
      return;
    }

    setState(() => _isSubmitting = true);
    bool success = false;
    try {
      success = await widget.onSave(
        paymentMethod: paymentMethod,
        amount: amount,
        date: date,
        file: _currentFile,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    // Only the sheet's owner pops the sheet — `uploadManualPayment` pops
    // only the loading dialog and the snackbar fires inside it. Popping
    // here once success is reported keeps the admin on the student list
    // (route below the sheet) instead of stacking an extra pop that
    // earlier dropped them back on the class picker.
    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Unggah Bukti Pembayaran',
      subtitle: 'Catat pembayaran manual siswa',
      icon: Icons.receipt_long_rounded,
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.85,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildBillInfo(),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),
          buildPaymentMethod(),
          const SizedBox(height: AppSpacing.md),
          buildAmount(),
          const SizedBox(height: AppSpacing.md),
          buildDate(),
          const SizedBox(height: AppSpacing.md),
          _FilePickerSection(
            selectedFile: _currentFile,
            isPicking: _isPicking,
            primaryColor: widget.primaryColor,
            getFileTypeText: _getFileTypeText,
            onPickFile: _handlePickFile,
            onClear: () => setState(() => _currentFile = null),
          ),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: _isSubmitting ? 'Menyimpan...' : 'Simpan',
        secondaryLabel: 'Batal',
        primaryColor: widget.primaryColor,
        primaryEnabled: !_isPicking && !_isSubmitting,
        onPrimary: _handleSave,
        onSecondary: _isSubmitting ? () {} : () => Navigator.pop(context),
      ),
    );
  }
}

/// File picker section widget.
class _FilePickerSection extends StatelessWidget {
  final File? selectedFile;
  final bool isPicking;
  final Color primaryColor;
  final String Function(String) getFileTypeText;
  final VoidCallback onPickFile;
  final VoidCallback onClear;

  const _FilePickerSection({
    required this.selectedFile,
    required this.isPicking,
    required this.primaryColor,
    required this.getFileTypeText,
    required this.onPickFile,
    required this.onClear,
  });

  @override
  Widget build(BuildContext c) {
    final hasFile = selectedFile != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(
          color: hasFile ? ColorUtils.success600 : ColorUtils.slate200,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            hasFile ? Icons.check_circle_rounded : Icons.upload_file,
            color: hasFile ? ColorUtils.success600 : ColorUtils.slate400,
            size: 40,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasFile
                ? 'File terpilih: ${selectedFile!.path.split('/').last}'
                : 'Pilih bukti pembayaran (opsional)',
            style: TextStyle(
              color: hasFile ? ColorUtils.success600 : ColorUtils.slate500,
              fontWeight: hasFile ? FontWeight.w600 : FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          if (hasFile) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              getFileTypeText(selectedFile!.path),
              style: TextStyle(fontSize: 11, color: ColorUtils.slate600),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasFile) ...[
                TextButton.icon(
                  onPressed: isPicking ? null : onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: ColorUtils.slate600,
                  ),
                  label: Text(
                    'Hapus',
                    style: TextStyle(
                      color: ColorUtils.slate600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              ElevatedButton.icon(
                onPressed: isPicking ? null : onPickFile,
                icon: isPicking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        hasFile ? Icons.swap_horiz_rounded : Icons.attach_file,
                        size: 16,
                        color: Colors.white,
                      ),
                label: Text(
                  hasFile ? 'Ganti File' : 'Pilih File',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
