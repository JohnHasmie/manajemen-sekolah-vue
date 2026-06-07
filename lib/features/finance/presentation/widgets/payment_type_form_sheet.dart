// Bottom sheet form for creating/editing payment types — v3 polish.
//
// Compared to the previous v3 pass, this version:
//
//   * Inlines every input widget (no more PaymentFormBuilders / Inputs
//     mixins on the render path) so the form's typography, spacing, and
//     colors stay aligned with the rest of the v3 admin sheets.
//   * Drops the duplicate "Periode Pembayaran" / "Tujuan Pembayaran" /
//     "Status" sub-labels. The shared `_SectionHeader` is now the single
//     source of section meaning, with a one-line helper underneath where
//     useful.
//   * Replaces the chunky tinted-fill TextField scaffold with a proper
//     v3 outlined input (kicker label above, white field, slate border,
//     focus ring in primary color).
//   * Replaces the two side-by-side Status chips with a single segmented
//     Aktif/Nonaktif control — fixes the previously dead `setState` in
//     PaymentFormBuildersMixin.buildStatusChip and reads cleaner.
//   * Tightens the period chip row to icon-left/label-right with a
//     primary tint when active.
//
// The inline UI building blocks live in `part` files under
// `payment_type_form/` so this orchestrator stays focused on state +
// the build() layout. They remain library-private (`_`-prefixed) and
// share this library's imports.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/currency_formatter.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/modern_date_picker.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/payment_form_handlers.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/payment_form_parsers.dart';

part 'payment_type_form/section_header.dart';
part 'payment_type_form/labeled_field.dart';
part 'payment_type_form/period_chips.dart';
part 'payment_type_form/goal_picker_tile.dart';
part 'payment_type_form/status_segmented.dart';
part 'payment_type_form/activation_fields.dart';

/// A bottom sheet form for adding or editing a payment type.
///
/// Receives optional [paymentType] data for editing, a [primaryColor]
/// for theming, an [onSaved] callback to refresh parent data, and
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

  /// Convenience helper that wires the sheet into the standard
  /// `AppBottomSheet.show` modal flow. Existing call sites still
  /// using `showModalBottomSheet(builder: PaymentTypeFormSheet(...))`
  /// keep working unchanged.
  static Future<void> show({
    required BuildContext context,
    required Color primaryColor,
    required VoidCallback onSaved,
    required void Function({
      Map<String, dynamic>? paymentType,
      required Function(Map<String, dynamic>) onSave,
    })
    onShowTargetSelection,
    Map<String, dynamic>? paymentType,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentTypeFormSheet(
        paymentType: paymentType,
        primaryColor: primaryColor,
        onSaved: onSaved,
        onShowTargetSelection: onShowTargetSelection,
      ),
    );
  }

  @override
  ConsumerState<PaymentTypeFormSheet> createState() =>
      _PaymentTypeFormSheetState();
}

class _PaymentTypeFormSheetState extends ConsumerState<PaymentTypeFormSheet>
    with PaymentFormParsersMixin, PaymentFormHandlersMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _periodController;
  Map<String, dynamic>? _goalData;
  late String _status;
  bool _saving = false;

  // Step 3 activation flow:
  //   * [_startDate] — when billing should kick in. Defaults to today
  //     for new Jenis; on edit, parsed from the row's start_date column.
  //   * [_dayOfMonth] — bill due-day (1-28). Only shown for periode
  //     = 'bulanan'. Defaults to 10 (matches common SPP practice).
  //
  // Both are nullable in the wire payload; the backend's
  // GenerateBillsForTypeAction falls back to safe defaults when null
  // (today + day-10), so older Jenis rows that don't have these
  // columns yet keep working.
  DateTime? _startDate;
  int? _dayOfMonth;

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
      // Backend rename: `payment_types.periode` → `payment_types.period`,
      // canonical values: `monthly` / `yearly` / `once`.
      text: pt?['period'] ?? pt?['periode'] ?? 'monthly',
    );
    _goalData = pt != null ? parseGoal(pt['goal']) : null;
    _status = (pt?['status'] == 'inactive') ? 'inactive' : 'active';

    // Seed activation fields. On edit, parse the ISO date from the
    // backend; on create, default to today (bills should generate now).
    final rawStart = pt?['start_date'];
    if (rawStart is String && rawStart.isNotEmpty) {
      _startDate = DateTime.tryParse(rawStart);
    }
    _startDate ??= DateTime.now();

    final rawDay = pt?['day_of_month'];
    if (rawDay is int) {
      _dayOfMonth = rawDay;
    } else if (rawDay is String) {
      _dayOfMonth = int.tryParse(rawDay);
    }
    // Default day-10 for new Jenis matches the backend's fallback.
    _dayOfMonth ??= 10;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.paymentType != null;
    final lang = ref.watch(languageRiverpod);
    final navy = widget.primaryColor;

    return AppBottomSheet(
      title: isEdit ? kFinEditPaymentType.tr : kFinAddPaymentType.tr,
      subtitle: isEdit
          ? kFinUpdatePaymentTypeDesc.tr
          : kFinCreatePaymentTypeDesc.tr,
      icon: Icons.credit_card_rounded,
      primaryColor: navy,
      maxHeightFactor: 0.92,
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          _SectionHeader(
            label: kFinBasicInformation.tr,
            icon: Icons.edit_note_rounded,
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: kFinPaymentTypeName.tr,
            controller: _nameController,
            hint: 'Misal: SPP September',
            icon: Icons.payments_rounded,
            primaryColor: navy,
          ),
          const SizedBox(height: 14),
          _LabeledField(
            label: kFinAmountIDR.tr,
            controller: _amountController,
            hint: 'Rp 0',
            icon: Icons.attach_money_rounded,
            primaryColor: navy,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            helper: 'Nilai default yang akan dibebankan ke setiap siswa.',
          ),
          const SizedBox(height: 14),
          _LabeledField(
            label: kFinDescriptionOptional.tr,
            controller: _descriptionController,
            hint: 'Catatan tambahan untuk wali kelas atau orang tua…',
            icon: Icons.notes_rounded,
            primaryColor: navy,
            maxLines: 3,
          ),
          const SizedBox(height: 22),
          _SectionHeader(
            label: kFinBillingPeriodHeader.tr,
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(height: 12),
          _PeriodChips(
            value: _periodController.text,
            onChanged: (v) => setState(() => _periodController.text = v),
            primaryColor: navy,
          ),
          const SizedBox(height: 22),
          // ── Activation section ─────────────────────────────────
          // "When should bills start being generated?" — date picker
          // for every periode, plus a day-of-month picker that only
          // appears for `bulanan` so non-monthly Jenis stay simple.
          _SectionHeader(
            label: kFinStartDate.tr,
            icon: Icons.event_available_rounded,
          ),
          const SizedBox(height: 12),
          _ActivationFields(
            startDate: _startDate ?? DateTime.now(),
            dayOfMonth: _dayOfMonth ?? 10,
            periode: _periodController.text,
            primaryColor: navy,
            onStartDateChanged: (d) => setState(() => _startDate = d),
            onDayOfMonthChanged: (d) => setState(() => _dayOfMonth = d),
          ),
          const SizedBox(height: 22),
          _SectionHeader(
            label: kFinRecipientTargetLabel.tr,
            icon: Icons.groups_rounded,
          ),
          const SizedBox(height: 12),
          _GoalPickerTile(
            goalData: _goalData,
            primaryColor: navy,
            description: getGoalDescription(_goalData),
            onTap: () {
              widget.onShowTargetSelection(
                paymentType: widget.paymentType,
                onSave: (goal) => setState(() => _goalData = goal),
              );
            },
          ),
          const SizedBox(height: 22),
          _SectionHeader(
            label: kFinActivationStatus.tr,
            icon: Icons.toggle_on_rounded,
          ),
          const SizedBox(height: 12),
          _StatusSegmented(
            value: _status,
            onChanged: (v) => setState(() => _status = v),
            primaryColor: navy,
          ),
          const SizedBox(height: 24),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: _saving
            ? 'Menyimpan…'
            : (isEdit ? 'Simpan perubahan' : 'Tambah jenis pembayaran'),
        primaryColor: navy,
        primaryEnabled: !_saving,
        secondaryLabel: lang.getTranslatedText(const {
          'en': 'Cancel',
          'id': 'Batal',
        }),
        onPrimary: _saving ? () {} : _handleSave,
        onSecondary: _saving ? () {} : () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await handleFormSubmit(
        context,
        nameController: _nameController,
        amountController: _amountController,
        periodController: _periodController,
        status: _status,
        goalData: _goalData,
        paymentType: widget.paymentType,
        onSaved: widget.onSaved,
        descriptionController: _descriptionController,
        startDate: _startDate,
        dayOfMonth: _dayOfMonth,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
