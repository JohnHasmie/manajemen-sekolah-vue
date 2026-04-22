// Bottom sheet form for creating/editing payment types.
//
// Extracted from admin_finance_screen.dart to reduce file size.
// Like a Vue component that handles the payment type CRUD form,
// receiving callbacks for save actions and target selection.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/currency_formatter.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/payment_form_builders.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/payment_form_handlers.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/payment_form_inputs.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/payment_form_parsers.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/payment_form_sections.dart';

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
  })
  onShowTargetSelection;

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

class _PaymentTypeFormSheetState extends ConsumerState<PaymentTypeFormSheet>
    with
        PaymentFormParsersMixin,
        PaymentFormBuildersMixin,
        PaymentFormHandlersMixin,
        PaymentFormSectionsMixin,
        PaymentFormInputsMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _periodController;
  Map<String, dynamic>? _goalData;
  late String _status;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
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
    _goalData = pt != null ? parseGoal(pt['goal']) : null;
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

  Color get _primaryColor => widget.primaryColor;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.paymentType != null;
    final lang = ref.read(languageRiverpod);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          buildFormHeader(
            isEdit,
            lang,
            _primaryColor,
            () => AppNavigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildDialogTextField(
                      controller: _nameController,
                      label: 'Nama Pembayaran',
                      icon: Icons.payment_rounded,
                      primaryColor: _primaryColor,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    buildDialogTextField(
                      controller: _descriptionController,
                      label: 'Deskripsi (Opsional)',
                      icon: Icons.description_rounded,
                      primaryColor: _primaryColor,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    buildDialogTextField(
                      controller: _amountController,
                      label: 'Jumlah (Rp)',
                      icon: Icons.attach_money_rounded,
                      primaryColor: _primaryColor,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    buildPeriodSection(_periodController, _primaryColor),
                    const SizedBox(height: AppSpacing.lg),
                    buildGoalSection(_goalData, () {
                      widget.onShowTargetSelection(
                        paymentType: widget.paymentType,
                        onSave: (goal) {
                          setState(() => _goalData = goal);
                        },
                      );
                    }),
                    const SizedBox(height: AppSpacing.lg),
                    buildStatusSection(
                      _status,
                      (newStatus) => setState(() => _status = newStatus),
                    ),
                  ],
                ),
              ),
            ),
          ),
          buildFormFooter(
            lang,
            () => AppNavigator.pop(context),
            () => handleFormSubmit(
              context,
              nameController: _nameController,
              amountController: _amountController,
              periodController: _periodController,
              status: _status,
              goalData: _goalData,
              paymentType: widget.paymentType,
              onSaved: widget.onSaved,
              descriptionController: _descriptionController,
            ),
          ),
        ],
      ),
    );
  }
}
