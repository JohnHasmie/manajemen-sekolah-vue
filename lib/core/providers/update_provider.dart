import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/shorebird_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

enum UpdateType { none, shorebirdPatch, nativeUpdate }

/// SharedPreferences key — last Shorebird patch number the user has
/// either applied (tapped "Segarkan Sekarang") or dismissed (tapped
/// "Nanti Saja"). Future polls compare the candidate patch number
/// against this and suppress the pop-up when they match. Re-arms for
/// the next genuinely-different patch number.
const String _kDismissedPatchKey = 'shorebird_dismissed_patch_number';

@immutable
class UpdateState {
  final UpdateType type;
  final bool isChecking;
  final String? version;

  /// Staged Shorebird patch number when [type] is shorebirdPatch.
  /// Captured so the dismiss handler can persist it without
  /// re-querying the updater service.
  final int? patchNumber;

  const UpdateState({
    this.type = UpdateType.none,
    this.isChecking = false,
    this.version,
    this.patchNumber,
  });

  UpdateState copyWith({
    UpdateType? type,
    bool? isChecking,
    String? version,
    int? patchNumber,
  }) {
    return UpdateState(
      type: type ?? this.type,
      isChecking: isChecking ?? this.isChecking,
      version: version ?? this.version,
      patchNumber: patchNumber ?? this.patchNumber,
    );
  }
}

class UpdateNotifier extends Notifier<UpdateState> {
  Timer? _checkTimer;

  @override
  UpdateState build() {
    ref.onDispose(() {
      _checkTimer?.cancel();
    });

    // Initial check after a short delay to let the app settle
    Future.delayed(const Duration(seconds: 5), () {
      checkUpdates();
    });

    // Periodic check for Shorebird patches (every 15 minutes)
    _checkTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      checkUpdates();
    });

    return const UpdateState();
  }

  Future<void> checkUpdates() async {
    if (state.isChecking) return;

    state = state.copyWith(isChecking: true);

    try {
      final shorebirdService = getIt<ShorebirdService>();
      final result = await shorebirdService.checkForUpdates();
      if (result.hasUpdate) {
        // Suppress the dialog when the staged patch matches what the
        // user has already acknowledged. Two scenarios this catches:
        //   1. User tapped "Segarkan Sekarang" but the restart didn't
        //      properly reboot the engine, so the patch is still
        //      `nextPatch` on the next 15-min poll → would otherwise
        //      re-fire the dialog forever.
        //   2. User tapped "Nanti Saja" — they explicitly opted out
        //      for this patch and shouldn't be nagged again until a
        //      newer patch ships.
        // A genuinely-newer patch (different number) does fire because
        // the equality check no longer holds.
        final dismissed = PreferencesService().getInt(_kDismissedPatchKey);
        if (dismissed != null &&
            result.patchNumber != null &&
            result.patchNumber == dismissed) {
          AppLogger.info(
            'update',
            'Shorebird patch ${result.patchNumber} already '
                'acknowledged by user — skipping dialog.',
          );
          state = state.copyWith(type: UpdateType.none, isChecking: false);
          return;
        }

        AppLogger.info(
          'update',
          'Shorebird patch ${result.patchNumber} ready.',
        );
        state = state.copyWith(
          type: UpdateType.shorebirdPatch,
          patchNumber: result.patchNumber,
          isChecking: false,
        );
        return;
      }

      state = state.copyWith(type: UpdateType.none, isChecking: false);
    } catch (e) {
      AppLogger.error('update', 'Error checking updates: $e');
      state = state.copyWith(isChecking: false);
    }
  }

  /// Persist the current patch number as "user has seen this" and
  /// drop the dialog out of state. Call from BOTH the apply path
  /// (Segarkan Sekarang) and the dismiss path (Nanti Saja) — either
  /// action means the user is done seeing this specific patch's
  /// pop-up.
  Future<void> acknowledgeCurrentPatch() async {
    final patchNumber = state.patchNumber;
    if (patchNumber != null) {
      await PreferencesService().setInt(_kDismissedPatchKey, patchNumber);
    }
    state = state.copyWith(type: UpdateType.none);
  }

  void reset() {
    state = state.copyWith(type: UpdateType.none);
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);