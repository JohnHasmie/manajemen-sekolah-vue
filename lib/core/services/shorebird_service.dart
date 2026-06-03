import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Result of a Shorebird update check.
///
/// `hasUpdate` is true when a patch has been downloaded and is staged
/// but not yet running. `patchNumber` is the staged patch's number —
/// used by the update provider to deduplicate "Update Tersedia" pop-ups
/// across periodic checks and restarts (so the same patch can't fire
/// the dialog twice for one user).
class ShorebirdUpdateResult {
  final bool hasUpdate;
  final int? patchNumber;

  const ShorebirdUpdateResult({required this.hasUpdate, this.patchNumber});

  const ShorebirdUpdateResult.none() : hasUpdate = false, patchNumber = null;
}

class ShorebirdService {
  final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Checks if a new Shorebird patch is available and downloaded.
  /// Returns the staged patch number alongside the availability flag
  /// so callers can persist a "user already saw this patch" marker.
  Future<ShorebirdUpdateResult> checkForUpdates() async {
    try {
      if (!_updater.isAvailable) {
        AppLogger.info(
          'shorebird',
          'Shorebird is not available on this device.',
        );
        return const ShorebirdUpdateResult.none();
      }

      // Check if a new patch is available
      final status = await _updater.checkForUpdate();

      if (status == UpdateStatus.outdated) {
        AppLogger.info(
          'shorebird',
          'New Shorebird patch available. Downloading...',
        );
        await _updater.update();
        AppLogger.info('shorebird', 'Shorebird patch downloaded and ready.');
        final staged = await _updater.readNextPatch();
        return ShorebirdUpdateResult(
          hasUpdate: true,
          patchNumber: staged?.number,
        );
      }

      // Check if an update was already downloaded but not yet applied
      // (typical on the next cold-launch after `update()` ran). When
      // the engine successfully boots the staged patch, currentPatch
      // catches up and we fall through to "no update".
      final nextPatch = await _updater.readNextPatch();
      final currentPatch = await _updater.readCurrentPatch();
      if (nextPatch != null &&
          (currentPatch == null || nextPatch.number != currentPatch.number)) {
        return ShorebirdUpdateResult(
          hasUpdate: true,
          patchNumber: nextPatch.number,
        );
      }

      return const ShorebirdUpdateResult.none();
    } catch (e) {
      AppLogger.error('shorebird', 'Error checking for Shorebird updates: $e');
      return const ShorebirdUpdateResult.none();
    }
  }

  /// Current patch number
  Future<int?> currentPatchNumber() async {
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      return null;
    }
  }
}
