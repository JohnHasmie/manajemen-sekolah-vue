import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/shorebird_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

enum UpdateType { none, shorebirdPatch, nativeUpdate }

@immutable
class UpdateState {
  final UpdateType type;
  final bool isChecking;
  final String? version;

  const UpdateState({
    this.type = UpdateType.none,
    this.isChecking = false,
    this.version,
  });

  UpdateState copyWith({
    UpdateType? type,
    bool? isChecking,
    String? version,
  }) {
    return UpdateState(
      type: type ?? this.type,
      isChecking: isChecking ?? this.isChecking,
      version: version ?? this.version,
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
      final hasPatch = await shorebirdService.checkForUpdates();
      if (hasPatch) {
        AppLogger.info('update', 'Shorebird patch ready.');
        state = state.copyWith(
          type: UpdateType.shorebirdPatch,
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

  void reset() {
    state = state.copyWith(type: UpdateType.none);
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);
