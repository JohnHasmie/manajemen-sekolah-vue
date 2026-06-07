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
//
// This orchestrator owns the State (session load/cache, lifecycle, and
// the top-level build() layout). The per-section render code and the
// user actions live in `part` files under `parent_bill_checkout/` as
// library-private extensions on `_ParentBillCheckoutScreenState`, and
// the `_CheckoutSession` model + format helpers live in a models part.
// They stay library-private and share this library's imports.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_payment_success_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/parent_bill_checkout_widgets.dart';

part 'parent_bill_checkout/checkout_chrome.dart';
part 'parent_bill_checkout/checkout_method_cards.dart';
part 'parent_bill_checkout/checkout_how_to.dart';
part 'parent_bill_checkout/checkout_actions.dart';
part 'parent_bill_checkout/checkout_session.dart';

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

  /// True while a payment-proof upload is in flight — drives the
  /// upload CTA loading state and prevents double-submits.
  bool _isUploading = false;

  /// Whether the "Cara bayar" accordion body is currently expanded.
  /// Defaults closed; the user opens it on demand. Resets implicitly
  /// when the method tab changes since the body content depends on
  /// `_method` and the user expects the accordion to feel fresh per
  /// tab.
  bool _howToExpanded = false;

  @override
  void initState() {
    super.initState();
    _session = _stubSession();
    _loadSession();
  }

  /// Thin forwarder to [setState] so the library-private `part`
  /// extensions (chrome / how-to / actions) can request a rebuild
  /// without tripping the analyzer's protected-member guard on
  /// `setState`. Behaviorally identical to calling `setState` directly.
  void _applyState(VoidCallback fn) => setState(fn);

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
}
