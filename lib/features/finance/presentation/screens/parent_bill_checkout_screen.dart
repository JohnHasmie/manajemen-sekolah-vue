// Bayar checkout — single-page payment surface for parent role.
//
// Phase 5 surface C. Replaces the placeholder "Bayar via Transfer"
// AppAlertDialog at billing_card.dart:_showPayDialog with a full
// checkout flow matching the v3 mockup.
//
// Layout (single scrollable page, no separate detail screens)
// -----------------------------------------------------------
//   • Compact title bar (back · "Bayar Tagihan" · help)
//   • Bill recap card (azure gradient): jenis + total + admin chip
//   • Method tabs (segmented control): QRIS · Virtual Account · Manual
//   • Per-tab content rendered inline:
//       - QRIS:   countdown chip + big QR + Salin nominal pill
//       - VA:     bank logo + 16-digit VA number + Salin
//       - Manual: rek sekolah list + upload bukti CTA
//   • Cara bayar accordion
//   • Status hint pill ("Status akan terupdate otomatis < 1 menit")
//   • Sticky footer: "Saya sudah bayar — Cek status" CTA
//
// Backend gateway integration (Midtrans / Xendit) is out of scope
// for this commit — the checkout response is stubbed locally. The
// service layer carries a TODO so the swap to real gateway only
// touches one file.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_payment_success_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/parent_bill_checkout_widgets.dart';

/// Push the Bayar checkout for [bill]. Returns `true` when the user
/// completed payment (so the caller can refresh the bill list);
/// `null` if they backed out without paying.
Future<bool?> openParentBillCheckout(
  BuildContext context, {
  required Map<String, dynamic> bill,
}) {
  return AppNavigator.push<bool?>(
    context,
    ParentBillCheckoutScreen(bill: bill),
  );
}

/// Single-page Bayar checkout. Bill payload is the same row object
/// the bills list passes to [BillingCard], so callers don't need
/// to massage data.
class ParentBillCheckoutScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> bill;

  const ParentBillCheckoutScreen({super.key, required this.bill});

  @override
  ConsumerState<ParentBillCheckoutScreen> createState() =>
      _ParentBillCheckoutScreenState();
}

enum _PayMethod { qris, va, manual }

/// Cache lifetime for a checkout session — short enough that a stale
/// gateway response doesn't sit indefinitely, long enough that quick
/// back-and-forth navigation skips redundant POSTs.
const Duration _sessionTtl = Duration(seconds: 60);

/// Process-wide checkout-session cache, keyed by
/// `"{userId}|{schoolId}|{billId}"`. The user/school scoping protects
/// against multi-account devices: if user A signs out and user B
/// signs in, B's session lookups can't ever resolve to A's cached
/// entries even if a bill ID happened to collide across schools.
///
/// Call [clearParentBillCheckoutCache] from the logout / school-switch
/// path to drop everything; the auth flow already clears the on-disk
/// `LocalCacheService`, so this in-memory cache rides alongside it.
final Map<String, _SessionCacheEntry> _sessionCache = {};

/// Flush the in-memory checkout-session cache. Called from the auth
/// logout path so a re-login on the same device starts cold.
void clearParentBillCheckoutCache() {
  _sessionCache.clear();
}

class _SessionCacheEntry {
  final _CheckoutSession session;
  final DateTime fetchedAt;

  _SessionCacheEntry({required this.session, required this.fetchedAt});

  bool get isFresh => DateTime.now().difference(fetchedAt) < _sessionTtl;
}

class _ParentBillCheckoutScreenState
    extends ConsumerState<ParentBillCheckoutScreen> {
  _PayMethod _method = _PayMethod.qris;

  /// Live checkout session. Initialized from the local stub so the
  /// page always has something to render, then overwritten by the
  /// backend response when [_loadSession] resolves.
  late _CheckoutSession _session;

  @override
  void initState() {
    super.initState();
    _session = _stubSession();
    _loadSession();
  }

  /// Initialize the checkout against the backend. The API enforces
  /// parent ownership of the bill and returns the QR / VA / manual
  /// bank list in one call. Errors are swallowed — we keep showing
  /// the local stub so a flaky network never blocks the UI.
  ///
  /// Sessions are cached for [_sessionTtl] keyed by bill ID. Same
  /// bill always returns the same stub VA, so reopening the screen
  /// within a minute reuses the prior response and skips a network
  /// hop. Cache misses still hit the API.
  /// Compose a user-scoped cache key. Reads the active dashboard
  /// state (set on login) so the cache silos per (user, school) — if
  /// no dashboard state exists yet (e.g., the screen was opened
  /// before the dashboard finished loading), fall back to the bill
  /// ID alone with a `_anon_` namespace so the entry never collides
  /// with a real user's cache.
  String _cacheKey(String billId) {
    final state = ref.read(dashboardProvider).value;
    final userId = state?.userData['id']?.toString() ?? '_anon_';
    final schoolId = state?.userData['school_id']?.toString() ?? '_no_school_';
    return '$userId|$schoolId|$billId';
  }

  Future<void> _loadSession() async {
    final billId = widget.bill['id']?.toString();
    if (billId == null || billId.isEmpty) return;

    final key = _cacheKey(billId);
    final cached = _sessionCache[key];
    if (cached != null && cached.isFresh) {
      setState(() {
        _session = cached.session;
      });
      return;
    }

    try {
      final response = await ApiService().post(
        '/bill/$billId/checkout',
        const {},
      );
      if (!mounted) return;
      final data = response is Map && response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : (response is Map ? Map<String, dynamic>.from(response) : null);
      if (data != null) {
        final fresh = _CheckoutSession.fromJson(data);
        _sessionCache[key] = _SessionCacheEntry(
          session: fresh,
          fetchedAt: DateTime.now(),
        );
        setState(() {
          _session = fresh;
        });
      }
    } catch (e) {
      AppLogger.error('parent-bill-checkout', e);
      // Keep the stub session so the user can still see how to pay.
    }
  }

  /// Local fallback for offline / error states. Mirrors the live
  /// backend defaults so the UI is identical visually.
  _CheckoutSession _stubSession() {
    final rawAmount = widget.bill['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '') ?? 0;
    return _CheckoutSession(
      amount: amount,
      qrisAdminFee: 0,
      vaAdminFee: 4000,
      manualAdminFee: 0,
      qrString: 'TAG-${widget.bill['id']}',
      vaNumber: '8077 0123 4567 8901',
      vaBank: 'BCA',
      manualBankList: const [
        ('BCA', '8077 1234 5678', 'Yayasan Sekolah'),
        ('Mandiri', '157 0001 2345 678', 'Yayasan Sekolah'),
        ('BNI', '0123 4567 89', 'Yayasan Sekolah'),
      ],
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTitleBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                children: [
                  _buildBillRecap(),
                  AppSpacing.v16,
                  _buildMethodTabs(),
                  AppSpacing.v16,
                  _buildMethodContent(),
                  AppSpacing.v12,
                  _buildHowToAccordion(),
                  AppSpacing.v12,
                  _buildStatusHint(),
                  AppSpacing.v24,
                ],
              ),
            ),
            _buildStickyFooter(),
          ],
        ),
      ),
    );
  }

  // ───────────────── pieces ─────────────────

  Widget _buildTitleBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: const Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => AppNavigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: ColorUtils.slate600,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Bayar Tagihan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                ),
              ),
            ),
          ),
          // Help button — opens the cara-bayar bottom sheet for
          // method-specific instructions. Stub for now.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.help_outline_rounded,
              size: 18,
              color: ColorUtils.slate600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRecap() {
    final billName = widget.bill['type']?.toString() ?? 'Tagihan';
    final studentName =
        widget.bill['student_name']?.toString() ??
        widget.bill['student']?['name']?.toString() ??
        '';
    final headerLabel = studentName.isEmpty
        ? billName.toUpperCase()
        : '${billName.toUpperCase()} · ${studentName.toUpperCase()}';
    final adminFee = _session.adminFeeFor(_method);
    final total = _session.totalFor(_method);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorUtils.brandAzure, ColorUtils.brandAzureDeep],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headerLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total dibayar',
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatRupiah(total),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (adminFee > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '+ admin ${_formatRupiah(adminFee)} ▾',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTabs() {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ParentCheckoutMethodTab(
            label: 'QRIS',
            caption: '⚡ Tercepat',
            active: _method == _PayMethod.qris,
            onTap: () => setState(() => _method = _PayMethod.qris),
          ),
          ParentCheckoutMethodTab(
            label: 'Virtual Acc.',
            caption: 'BCA / Mandiri',
            active: _method == _PayMethod.va,
            onTap: () => setState(() => _method = _PayMethod.va),
          ),
          ParentCheckoutMethodTab(
            label: 'Manual',
            caption: 'Upload bukti',
            active: _method == _PayMethod.manual,
            onTap: () => setState(() => _method = _PayMethod.manual),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodContent() {
    switch (_method) {
      case _PayMethod.qris:
        return _buildQrisCard();
      case _PayMethod.va:
        return _buildVaCard();
      case _PayMethod.manual:
        return _buildManualCard();
    }
  }

  Widget _buildQrisCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ParentCheckoutCountdownChip(expires: _session.expiresAt),
              const Spacer(),
              Text(
                'Simpan QR ↓',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.brandAzureDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Big QR placeholder. Real implementation passes
          // _session.qrString to a QR painter (e.g. qr_flutter).
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 160,
              height: 160,
              color: const Color(0xFF0F172A),
              alignment: Alignment.center,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  'QRIS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.brandAzureDeep,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Salin nominal pill
          ParentCheckoutCopyPill(
            label: 'Nominal',
            value: _formatRupiah(_session.totalFor(_method)),
            onCopy: () => _toastCopied('Nominal'),
          ),
        ],
      ),
    );
  }

  Widget _buildVaCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bank logo placeholder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F4FAA),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _session.vaBank,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'NOMOR VIRTUAL ACCOUNT',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  _session.vaNumber,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              ParentCheckoutCopyPill(
                value: 'Salin',
                onCopy: () => _toastCopied('Nomor VA'),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          Text(
            'JUMLAH',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatRupiah(_session.totalFor(_method)),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+ admin ${_formatRupiah(_session.adminFeeFor(_method))}',
                style: TextStyle(fontSize: 9.5, color: ColorUtils.slate500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRANSFER KE REKENING SEKOLAH',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final bank in _session.manualBankList) ...[
            ParentCheckoutBankRow(
              bank: bank.$1,
              account: bank.$2,
              owner: bank.$3,
              onCopy: () => _toastCopied('Nomor rekening ${bank.$1}'),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          // Upload bukti CTA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.upload_file_rounded,
                  size: 16,
                  color: ColorUtils.brandAzureDeep,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sudah transfer? Upload bukti',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.brandAzureDeep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToAccordion() {
    final tip = switch (_method) {
      _PayMethod.qris => 'Buka GoPay / OVO / Dana / m-banking → Scan',
      _PayMethod.va => 'Buka m-banking → m-Transfer → Virtual Account',
      _PayMethod.manual => 'Transfer lalu unggah foto bukti di atas',
    };
    final title = switch (_method) {
      _PayMethod.qris => 'Cara bayar dengan QRIS',
      _PayMethod.va => 'Cara bayar via Virtual Account',
      _PayMethod.manual => 'Cara bayar transfer manual',
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tip,
                  style: TextStyle(fontSize: 9.5, color: ColorUtils.slate500),
                ),
              ],
            ),
          ),
          Text(
            '▾',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ColorUtils.brandAzureDeep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHint() {
    final manual = _method == _PayMethod.manual;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: manual ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: manual ? const Color(0xFFF59E0B) : ColorUtils.success600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              manual
                  ? 'Verifikasi admin 1–24 jam setelah upload bukti'
                  : 'Status akan terupdate otomatis < 1 menit',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: manual ? const Color(0xFF92400E) : ColorUtils.success600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFF1F5F9))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _onCheckStatus,
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorUtils.brandAzureDeep,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Saya sudah bayar — Cek status',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ───────────── helpers ─────────────

  Future<void> _onCheckStatus() async {
    // Stub: pretend the gateway confirmed payment. Real
    // implementation polls /bill/{id}/status here and only pushes
    // success when the response is "paid".
    final billName = widget.bill['type']?.toString() ?? 'Tagihan';
    final studentName =
        widget.bill['student_name']?.toString() ??
        widget.bill['student']?['name']?.toString() ??
        'Anak';
    final result = await AppNavigator.push<bool>(
      context,
      ParentPaymentSuccessScreen(
        billName: billName,
        studentName: studentName,
        methodLabel: _methodLabel,
        amount: _session.amount,
        adminFee: _session.adminFeeFor(_method),
        isManualPending: _method == _PayMethod.manual,
      ),
    );
    if (result == true && mounted) {
      AppNavigator.pop(context, true);
    }
  }

  String get _methodLabel {
    switch (_method) {
      case _PayMethod.qris:
        return 'QRIS';
      case _PayMethod.va:
        return '${_session.vaBank} Virtual Account';
      case _PayMethod.manual:
        return 'Transfer manual';
    }
  }

  void _toastCopied(String label) {
    SnackBarUtils.showSuccess(context, '$label berhasil disalin');
  }
}

/// Mirror of the JSON returned by `POST /bill/{id}/checkout`. The
/// shape matches a typical Midtrans Snap response so swapping the
/// stub gateway for a real provider is a one-method change.
class _CheckoutSession {
  final double amount;
  final double qrisAdminFee;
  final double vaAdminFee;
  final double manualAdminFee;
  final String qrString;
  final String vaNumber;
  final String vaBank;
  final List<(String bank, String account, String owner)> manualBankList;
  final DateTime expiresAt;

  _CheckoutSession({
    required this.amount,
    required this.qrisAdminFee,
    required this.vaAdminFee,
    required this.manualAdminFee,
    required this.qrString,
    required this.vaNumber,
    required this.vaBank,
    required this.manualBankList,
    required this.expiresAt,
  });

  /// Build a session from the backend JSON envelope. Tolerates legacy
  /// or partial payloads by falling back to safe defaults.
  factory _CheckoutSession.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v, {double fallback = 0}) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;

    final rawList = json['manual_bank_list'];
    final banks = <(String, String, String)>[];
    if (rawList is List) {
      for (final entry in rawList) {
        if (entry is Map) {
          banks.add((
            (entry['bank'] ?? '').toString(),
            (entry['account_number'] ?? '').toString(),
            (entry['account_name'] ?? '').toString(),
          ));
        }
      }
    }

    DateTime expires;
    final rawExpires = json['expires_at']?.toString();
    if (rawExpires != null && rawExpires.isNotEmpty) {
      expires =
          DateTime.tryParse(rawExpires) ??
          DateTime.now().add(const Duration(hours: 24));
    } else {
      expires = DateTime.now().add(const Duration(hours: 24));
    }

    return _CheckoutSession(
      amount: asDouble(json['amount']),
      qrisAdminFee: asDouble(json['qris_admin_fee']),
      vaAdminFee: asDouble(json['va_admin_fee'], fallback: 4000),
      manualAdminFee: asDouble(json['manual_admin_fee']),
      qrString: (json['qr_string'] ?? '').toString(),
      vaNumber: (json['va_number'] ?? '').toString(),
      vaBank: (json['va_bank'] ?? 'BCA').toString(),
      manualBankList: banks,
      expiresAt: expires,
    );
  }

  /// Per-method admin fee picker. The screen passes the active tab
  /// in so total/breakdown rows always reflect the right surcharge.
  double adminFeeFor(_PayMethod method) {
    switch (method) {
      case _PayMethod.qris:
        return qrisAdminFee;
      case _PayMethod.va:
        return vaAdminFee;
      case _PayMethod.manual:
        return manualAdminFee;
    }
  }

  double totalFor(_PayMethod method) => amount + adminFeeFor(method);
}

String _formatRupiah(double amount) {
  final whole = amount.round();
  final s = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final remain = s.length - i;
    buf.write(s[i]);
    if (remain > 1 && (remain - 1) % 3 == 0) buf.write('.');
  }
  return 'Rp $buf';
}
