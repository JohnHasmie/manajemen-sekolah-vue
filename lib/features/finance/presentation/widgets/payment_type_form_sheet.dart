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
      text: pt?['periode'] ?? 'bulanan',
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
      title: isEdit ? 'Ubah jenis pembayaran' : 'Tambah jenis pembayaran',
      subtitle: isEdit
          ? 'Perbarui detail jenis pembayaran berikut.'
          : 'Buat jenis pembayaran baru untuk dijadwalkan ke siswa.',
      icon: Icons.credit_card_rounded,
      primaryColor: navy,
      maxHeightFactor: 0.92,
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          const _SectionHeader(
            label: 'INFORMASI DASAR',
            icon: Icons.edit_note_rounded,
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'NAMA JENIS PEMBAYARAN',
            controller: _nameController,
            hint: 'Misal: SPP September',
            icon: Icons.payments_rounded,
            primaryColor: navy,
          ),
          const SizedBox(height: 14),
          _LabeledField(
            label: 'JUMLAH (RP)',
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
            label: 'DESKRIPSI · OPSIONAL',
            controller: _descriptionController,
            hint: 'Catatan tambahan untuk wali kelas atau orang tua…',
            icon: Icons.notes_rounded,
            primaryColor: navy,
            maxLines: 3,
          ),
          const SizedBox(height: 22),
          const _SectionHeader(
            label: 'PERIODE PENAGIHAN',
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
          const _SectionHeader(
            label: 'MULAI AKTIF',
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
          const _SectionHeader(
            label: 'TARGET PENERIMA',
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
          const _SectionHeader(
            label: 'STATUS AKTIVASI',
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

// --- Inline UI building blocks ------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: ColorUtils.slate500),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: ColorUtils.slate100)),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color primaryColor;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? helper;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.primaryColor,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          cursorColor: primaryColor,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate400,
            ),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(icon, size: 18, color: ColorUtils.slate400),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 38,
              minHeight: 0,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: maxLines > 1 ? 12 : 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ColorUtils.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ColorUtils.slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 1.4),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: TextStyle(
              fontSize: 10.5,
              color: ColorUtils.slate500,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _PeriodChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final Color primaryColor;

  const _PeriodChips({
    required this.value,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // Value strings must match CreatePaymentTypeRequest's `in:` rule
    // exactly. The legacy `'sekali bayar'` string (with a space) was
    // rejected by validation, surfacing as a generic "Gagal memproses"
    // toast. Use the same lowercase pattern as the other three so the
    // backend accepts it.
    const options = [
      _PeriodOption('sekali', 'Sekali', Icons.looks_one_rounded),
      _PeriodOption('bulanan', 'Bulanan', Icons.calendar_view_month_rounded),
      _PeriodOption('semester', 'Semester', Icons.date_range_rounded),
      _PeriodOption('tahunan', 'Tahunan', Icons.calendar_today_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              Expanded(
                child: _PeriodChipTile(
                  option: options[i],
                  selected: value == options[i].value,
                  primaryColor: primaryColor,
                  onTap: () => onChanged(options[i].value),
                ),
              ),
              if (i < options.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Sekali = tagihan sekali jalan, Bulanan/Semester/Tahunan = berulang otomatis.',
          style: TextStyle(
            fontSize: 10.5,
            color: ColorUtils.slate500,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _PeriodOption {
  final String value;
  final String label;
  final IconData icon;
  const _PeriodOption(this.value, this.label, this.icon);
}

class _PeriodChipTile extends StatelessWidget {
  final _PeriodOption option;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _PeriodChipTile({
    required this.option,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: 0.10)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? primaryColor : ColorUtils.slate200,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                size: 18,
                color: selected ? primaryColor : ColorUtils.slate500,
              ),
              const SizedBox(height: 4),
              Text(
                option.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? primaryColor : ColorUtils.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalPickerTile extends StatelessWidget {
  final Map<String, dynamic>? goalData;
  final Color primaryColor;
  final String description;
  final VoidCallback onTap;

  const _GoalPickerTile({
    required this.goalData,
    required this.primaryColor,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasGoal = goalData != null && goalData!.isNotEmpty;
    final tint = hasGoal ? const Color(0xFF059669) : primaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasGoal
                  ? tint.withValues(alpha: 0.4)
                  : ColorUtils.slate200,
              width: hasGoal ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  hasGoal ? Icons.check_circle_rounded : Icons.groups_rounded,
                  size: 18,
                  color: tint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasGoal ? 'Target dipilih' : 'Belum ada target',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: hasGoal ? tint : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasGoal
                          ? description
                          : 'Pilih kelas, tingkat, atau siswa yang akan ditagih.',
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: ColorUtils.slate400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusSegmented extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final Color primaryColor;

  const _StatusSegmented({
    required this.value,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatusSegment(
              label: 'Aktif',
              icon: Icons.check_circle_rounded,
              activeColor: const Color(0xFF059669),
              selected: value == 'active',
              onTap: () => onChanged('active'),
            ),
          ),
          Expanded(
            child: _StatusSegment(
              label: 'Nonaktif',
              icon: Icons.pause_circle_filled_rounded,
              activeColor: ColorUtils.slate600,
              selected: value == 'inactive',
              onTap: () => onChanged('inactive'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color activeColor;
  final bool selected;
  final VoidCallback onTap;

  const _StatusSegment({
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? activeColor : ColorUtils.slate500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? activeColor : ColorUtils.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Activation section — start_date picker + monthly day-of-month picker
// ─────────────────────────────────────────────────────────────────────

/// Renders the "Mulai aktif" inputs.
///
/// Always shows the start_date picker so every periode (sekali too) has
/// a clear "this is when billing kicks in" anchor. The day-of-month
/// picker only appears when periode is `bulanan` since the other
/// periodes derive their due_date from start_date alone.
class _ActivationFields extends StatelessWidget {
  final DateTime startDate;
  final int dayOfMonth;
  final String periode;
  final Color primaryColor;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<int> onDayOfMonthChanged;

  const _ActivationFields({
    required this.startDate,
    required this.dayOfMonth,
    required this.periode,
    required this.primaryColor,
    required this.onStartDateChanged,
    required this.onDayOfMonthChanged,
  });

  // Indonesian month names for the human-readable date display.
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  /// Periode-aware helper text. We don't want to claim "tagihan tiap
  /// tanggal X" for a Jenis that only bills once.
  String _startHelper() {
    switch (periode) {
      case 'bulanan':
        return 'Tagihan akan dibuat mulai bulan ini.';
      case 'semester':
        return 'Tagihan semester akan dibuat dari tanggal ini.';
      case 'tahunan':
        return 'Tagihan tahunan akan dibuat dari tanggal ini.';
      case 'sekali':
      default:
        return 'Tanggal jatuh tempo tagihan.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBulanan = periode == 'bulanan';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DatePickerTile(
          label: 'TANGGAL MULAI',
          value: _formatDate(startDate),
          icon: Icons.event_rounded,
          primaryColor: primaryColor,
          onTap: () async {
            final picked = await showModernDatePicker(
              context: context,
              initialDate: startDate,
              title: 'Pilih tanggal mulai',
              firstDate: DateTime(DateTime.now().year - 1),
              lastDate: DateTime(DateTime.now().year + 5),
              primaryColor: primaryColor,
            );
            if (picked != null) onStartDateChanged(picked);
          },
          helper: _startHelper(),
        ),
        if (isBulanan) ...[
          const SizedBox(height: 14),
          _DayOfMonthStepper(
            value: dayOfMonth,
            onChanged: onDayOfMonthChanged,
            primaryColor: primaryColor,
          ),
        ],
      ],
    );
  }
}

/// A read-only tile that opens a date picker on tap.
class _DatePickerTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color primaryColor;
  final VoidCallback onTap;
  final String? helper;

  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: ColorUtils.slate400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: ColorUtils.slate400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: TextStyle(
              fontSize: 10.5,
              color: ColorUtils.slate500,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

/// Day-of-month picker as a — / + stepper with the value in the middle.
/// Clamped 1-28 to match the backend rule (avoids Feb-29 edge cases).
class _DayOfMonthStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final Color primaryColor;

  const _DayOfMonthStepper({
    required this.value,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'JATUH TEMPO TIAP TANGGAL',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Row(
            children: [
              _StepperButton(
                icon: Icons.remove_rounded,
                primaryColor: primaryColor,
                enabled: value > 1,
                onTap: () => onChanged(value - 1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Tanggal $value',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              _StepperButton(
                icon: Icons.add_rounded,
                primaryColor: primaryColor,
                enabled: value < 28,
                onTap: () => onChanged(value + 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Berlaku 1-28 untuk menghindari masalah Februari.',
          style: TextStyle(
            fontSize: 10.5,
            color: ColorUtils.slate500,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final Color primaryColor;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.primaryColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: enabled
                ? primaryColor.withValues(alpha: 0.10)
                : ColorUtils.slate100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? primaryColor : ColorUtils.slate400,
          ),
        ),
      ),
    );
  }
}
