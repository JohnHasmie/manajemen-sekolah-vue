// Dialog for selecting a month and academic year, then generating bills
// for a given payment type.
//
// Extracted from `_confirmGenerateBills` in admin_finance_screen.dart.
// Like a Vue `<GenerateBillsDialog :paymentType="pt" @generated="reload" />`
// component — it fetches academic years itself, lets the admin pick a month,
// then pops with the chosen params so the parent can call the generate API.
//
// The parent is responsible for calling FinanceService.generateBills() after
// the dialog resolves (via [onGenerated] callback), so no service call lives
// inside this widget.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';
import 'package:manajemensekolah/features/settings/data/academic_service.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/generate_bills_dialog_ui_mixin.dart';

/// Full-screen dialog for generating bills for a payment type.
///
/// Shows a month grid (with already-generated months disabled) and an
/// academic-year dropdown.  On confirm, calls [onGenerated] so the parent
/// can reload its data.
///
/// In Vue terms: `<GenerateBillsDialog :paymentType="pt" @generated="reload" />`
class GenerateBillsDialog extends StatefulWidget {
  /// The payment-type map from the API (needs at minimum `id` and `name`).
  final Map<String, dynamic> paymentType;

  /// Primary theme colour already resolved by the parent (`_getPrimaryColor()`).
  final Color primaryColor;

  /// Gradient used for the dialog header — same as `_getCardGradient()`.
  final LinearGradient cardGradient;

  /// Called after the generate-bills API call succeeds, so the parent can
  /// refresh its list (equivalent to `_loadData(useCache: false)`).
  final VoidCallback onGenerated;

  const GenerateBillsDialog({
    super.key,
    required this.paymentType,
    required this.primaryColor,
    required this.cardGradient,
    required this.onGenerated,
  });

  @override
  State<GenerateBillsDialog> createState() => _GenerateBillsDialogState();
}

class _GenerateBillsDialogState extends State<GenerateBillsDialog>
    with GenerateBillsDialogUiMixin {
  // Currently selected month name (Indonesian), defaults to current month.
  late String _selectedMonth;
  String? _selectedAcademicYearId;

  List<dynamic> _academicYears = [];
  List<String> _generatedMonths = [];

  bool _isLoadingYears = true;
  bool _isLoadingGenerated = false;

  // Mixin property accessors
  @override
  Color get primaryColor => widget.primaryColor;

  @override
  LinearGradient get cardGradient => widget.cardGradient;

  @override
  Map<String, dynamic> get paymentType => widget.paymentType;

  @override
  String get selectedMonth => _selectedMonth;

  @override
  set selectedMonth(String value) => _selectedMonth = value;

  @override
  String? get selectedAcademicYearId => _selectedAcademicYearId;

  @override
  set selectedAcademicYearId(String? value) => _selectedAcademicYearId = value;

  @override
  List<dynamic> get academicYears => _academicYears;

  @override
  set academicYears(List<dynamic> value) => _academicYears = value;

  @override
  List<String> get generatedMonths => _generatedMonths;

  @override
  set generatedMonths(List<String> value) => _generatedMonths = value;

  @override
  bool get isLoadingYears => _isLoadingYears;

  @override
  set isLoadingYears(bool value) => _isLoadingYears = value;

  @override
  bool get isLoadingGenerated => _isLoadingGenerated;

  @override
  set isLoadingGenerated(bool value) => _isLoadingGenerated = value;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateFormat('MMMM', 'id_ID').format(DateTime.now());
    _fetchAcademicYears();
  }

  // ─── Data fetching ───────────────────────────────────────────────────────────

  Future<void> _fetchAcademicYears() async {
    try {
      final years = await getIt<ApiAcademicServices>().getAcademicYears();
      if (!mounted) return;

      final activeYear = years.firstWhere(
        (y) => y['current'] == true || y['status'] == 'active',
        orElse: () => years.isNotEmpty ? years.first : null,
      );

      setState(() {
        _academicYears = years;
        _isLoadingYears = false;
        if (activeYear != null) {
          _selectedAcademicYearId = activeYear['id'].toString();
          _isLoadingGenerated = true;
        }
      });

      if (_selectedAcademicYearId != null) {
        await _fetchGeneratedMonths(_selectedAcademicYearId!);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingYears = false);
    }
  }

  Future<void> _fetchGeneratedMonths(String academicYearId) async {
    try {
      final genMonths = await FinanceService.getGeneratedMonths(
        paymentTypeId: widget.paymentType['id'].toString(),
        academicYearId: academicYearId,
      );
      if (mounted) {
        setState(() {
          _generatedMonths = genMonths;
          _isLoadingGenerated = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingGenerated = false);
    }
  }

  @override
  void _notifyAcademicYearChanged(String academicYearId) {
    _fetchGeneratedMonths(academicYearId);
  }

  // ─── Generate action (called when user taps the Generate button) ─────────────

  Future<void> _generate() async {
    if (_selectedAcademicYearId == null) return;
    AppNavigator.pop(context); // close the dialog first

    try {
      final response = await FinanceService.generateBills(
        paymentTypeId: widget.paymentType['id'].toString(),
        month: _selectedMonth,
        academicYearId: _selectedAcademicYearId!,
      );

      if (mounted) {
        String message = 'Tagihan berhasil dibuat';
        if (response != null && response['message'] != null) {
          message = response['message'];
        }
        if (response != null &&
            response['errors'] != null &&
            (response['errors'] as List).isNotEmpty) {
          message = (response['errors'] as List).join('\n');
        }
        SnackBarUtils.showSuccess(context, message);
      }

      widget.onGenerated();
    } catch (error) {
      AppLogger.error('finance', error);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToGenerate.tr}: ${ErrorUtils.getFriendlyMessage(error)}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canGenerate =
        _selectedAcademicYearId != null &&
        !_generatedMonths.contains(_selectedMonth);

    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildHeader(),
            buildContent(),
            buildFooter(canGenerate, _generate),
          ],
        ),
      ),
    );
  }
}
