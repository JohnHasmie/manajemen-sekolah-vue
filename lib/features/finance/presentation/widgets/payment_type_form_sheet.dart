// Bottom sheet form for creating/editing payment types.
//
// Extracted from admin_finance_screen.dart to reduce file size.
// Like a Vue component that handles the payment type CRUD form,
// receiving callbacks for save actions and target selection.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/currency_formatter.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// A bottom sheet form for adding or editing a payment type.
///
/// Receives optional [paymentType] data for editing, a [primaryColor] for
/// theming, an [onSaved] callback to refresh parent data, and
/// [onShowTargetSelection] to open the target selection modal.
class PaymentTypeFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? paymentType;
  final Color primaryColor;
  final VoidCallback onSaved;
  final void Function({
    Map<String, dynamic>? paymentType,
    required Function(Map<String, dynamic>) onSave,
  }) onShowTargetSelection;

  const PaymentTypeFormSheet({
    super.key,
    this.paymentType,
    required this.primaryColor,
    required this.onSaved,
    required this.onShowTargetSelection,
  });

  @override
  ConsumerState<PaymentTypeFormSheet> createState() =>
      _PaymentTypeFormSheetState();
}

class _PaymentTypeFormSheetState extends ConsumerState<PaymentTypeFormSheet> {
  final ApiService _apiService = ApiService();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _periodController;
  Map<String, dynamic>? _goalData;
  late String _status;

  @override
  void initState() {
    super.initState();
    final pt = widget.paymentType;
    _nameController = TextEditingController(text: pt?['name']);
    _descriptionController = TextEditingController(text: pt?['description']);
    _amountController = TextEditingController(
      text: pt?['amount'] != null
          ? NumberFormat.currency(
              locale: 'id_ID',
              symbol: 'Rp ',
              decimalDigits: 0,
            ).format(double.tryParse(pt!['amount'].toString()) ?? 0)
          : '',
    );
    _periodController = TextEditingController(
      text: pt?['periode'] ?? 'bulanan',
    );
    _goalData = pt != null ? _parseGoal(pt['goal']) : null;
    _status = (pt?['status'] == 'active')
        ? 'active'
        : (pt?['status'] == 'inactive' ? 'inactive' : 'active');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _parseGoal(dynamic goalData) {
    if (goalData == null) return {};
    if (goalData is Map<String, dynamic>) return goalData;
    if (goalData is String) {
      try {
        return json.decode(goalData) as Map<String, dynamic>;
      } catch (e) {
        AppLogger.error('finance', e);
        return {};
      }
    }
    return {};
  }

  String _getGoalDescription(dynamic goalData) {
    final parsedGoal = _parseGoal(goalData);
    return parsedGoal['description'] ?? 'Tujuan pembayaran';
  }

  Color get _primaryColor => widget.primaryColor;

  Widget _buildPeriodChip(String value, String label, IconData icon) {
    final isSelected = _periodController.text == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _periodController.text = value;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _primaryColor.withValues(alpha: 0.12)
              : ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(
            color: isSelected ? _primaryColor : ColorUtils.slate200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? _primaryColor : ColorUtils.slate500,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _primaryColor : ColorUtils.slate600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    String value,
    String label,
    Color color,
    IconData icon,
  ) {
    final isSelected = (_status) == value;
    return GestureDetector(
      onTap: () => setState(() => _status = value),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(
            color: isSelected ? color : ColorUtils.slate200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : ColorUtils.slate400,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : ColorUtils.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.paymentType != null;
    final lang = ref.read(languageRiverpod);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _primaryColor,
                  _primaryColor.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit
                            ? lang.getTranslatedText(
                                AppLocalizations.editPaymentType,
                              )
                            : lang.getTranslatedText(
                                AppLocalizations.addPaymentType,
                              ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isEdit
                            ? 'Ubah data jenis pembayaran'
                            : 'Tambah jenis pembayaran baru',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => AppNavigator.pop(context),
                ),
              ],
            ),
          ),

          // Form Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama
                    _buildDialogTextField(
                      controller: _nameController,
                      label: 'Nama Pembayaran',
                      icon: Icons.payment_rounded,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Deskripsi
                    _buildDialogTextField(
                      controller: _descriptionController,
                      label: 'Deskripsi (Opsional)',
                      icon: Icons.description_rounded,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Jumlah
                    _buildDialogTextField(
                      controller: _amountController,
                      label: 'Jumlah (Rp)',
                      icon: Icons.attach_money_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    // Periode section
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 15,
                          color: ColorUtils.slate600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Periode Pembayaran',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPeriodChip(
                            'sekali bayar',
                            'Sekali Bayar',
                            Icons.looks_one_rounded,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildPeriodChip(
                            'bulanan',
                            'Bulanan',
                            Icons.calendar_view_month_rounded,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildPeriodChip(
                            'semester',
                            'Semester',
                            Icons.date_range_rounded,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildPeriodChip(
                            'tahunan',
                            'Tahunan',
                            Icons.calendar_today_rounded,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    // Tujuan Pembayaran
                    Row(
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          size: 15,
                          color: ColorUtils.slate600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tujuan Pembayaran',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        widget.onShowTargetSelection(
                          paymentType: widget.paymentType,
                          onSave: (goal) {
                            setState(() => _goalData = goal);
                          },
                        );
                      },
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _goalData != null && _goalData!.isNotEmpty
                              ? ColorUtils.success600.withValues(alpha: 0.06)
                              : ColorUtils.slate50,
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          border: Border.all(
                            color: _goalData != null && _goalData!.isNotEmpty
                                ? ColorUtils.success600.withValues(alpha: 0.4)
                                : ColorUtils.slate200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (_goalData != null &&
                                            _goalData!.isNotEmpty
                                        ? ColorUtils.success600
                                        : ColorUtils.corporateBlue600)
                                    .withValues(alpha: 0.12),
                                borderRadius: const BorderRadius.all(Radius.circular(10)),
                              ),
                              child: Icon(
                                _goalData != null && _goalData!.isNotEmpty
                                    ? Icons.check_circle_rounded
                                    : Icons.groups_rounded,
                                size: 18,
                                color: _goalData != null &&
                                        _goalData!.isNotEmpty
                                    ? ColorUtils.success600
                                    : ColorUtils.corporateBlue600,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _goalData != null && _goalData!.isNotEmpty
                                        ? 'Tujuan Dipilih'
                                        : 'Belum ada tujuan',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _goalData != null &&
                                              _goalData!.isNotEmpty
                                          ? ColorUtils.success600
                                          : ColorUtils.slate600,
                                    ),
                                  ),
                                  Text(
                                    _getGoalDescription(_goalData),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ColorUtils.slate500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: ColorUtils.slate400,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    // Status section
                    Row(
                      children: [
                        Icon(
                          Icons.toggle_on_rounded,
                          size: 15,
                          color: ColorUtils.slate600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusChip(
                            'active',
                            'Aktif',
                            ColorUtils.success600,
                            Icons.check_circle_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatusChip(
                            'inactive',
                            'Non-Aktif',
                            ColorUtils.error600,
                            Icons.cancel_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer Actions
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                      ),
                      child: Text(
                        lang.getTranslatedText({
                          'en': 'Cancel',
                          'id': 'Batal',
                        }),
                        style: TextStyle(
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _onSubmit(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        lang.getTranslatedText({
                          'en': 'Save',
                          'id': 'Simpan',
                        }),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmit(BuildContext context) async {
    if (_nameController.text.isEmpty || _amountController.text.isEmpty) {
      SnackBarUtils.showError(context, 'Nama dan jumlah harus diisi');
      return;
    }

    final parsedAmount = CurrencyInputFormatter.parseCurrency(
      _amountController.text,
    );

    if (parsedAmount <= 0) {
      SnackBarUtils.showError(context, 'Jumlah harus lebih besar dari Rp 0');
      return;
    }

    if (_goalData == null) {
      SnackBarUtils.showError(context, 'Tujuan pembayaran harus dipilih');
      return;
    }

    try {
      final data = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'amount': CurrencyInputFormatter.parseCurrency(_amountController.text),
        'periode': _periodController.text,
        'status': _status == 'active' ? 'active' : 'inactive',
        'goal': _goalData,
      };

      if (widget.paymentType == null) {
        await _apiService.post('/payment-types', data);
      } else {
        await _apiService.put(
          '/payment-types/${widget.paymentType!['id']}',
          data,
        );
      }

      if (context.mounted) {
        AppNavigator.pop(context);
      }
      widget.onSaved();

      if (context.mounted) {
        SnackBarUtils.showSuccess(
          context,
          AppLocalizations.dataSavedSuccessfully.tr,
        );
      }
    } catch (error) {
      AppLogger.error('finance', error);
      if (context.mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToSave.tr}: ${ErrorUtils.getFriendlyMessage(error)}',
        );
      }
    }
  }
}
