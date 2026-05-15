import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

class ShorebirdService {
  final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Checks if a new Shorebird patch is available and downloaded.
  /// Returns true if an update is ready to be applied (app needs restart).
  Future<bool> checkForUpdates() async {
    try {
      if (!_updater.isAvailable) {
        AppLogger.info('shorebird', 'Shorebird is not available on this device.');
        return false;
      }

      // Check if a new patch is available
      final status = await _updater.checkForUpdate();

      if (status == UpdateStatus.outdated) {
        AppLogger.info('shorebird', 'New Shorebird patch available. Downloading...');
        await _updater.update();
        AppLogger.info('shorebird', 'Shorebird patch downloaded and ready.');
        return true;
      }

      // Check if an update was already downloaded but not yet applied
      final nextPatch = await _updater.readNextPatch();
      final currentPatch = await _updater.readCurrentPatch();
      if (nextPatch != null && (currentPatch == null || nextPatch.number != currentPatch.number)) {
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('shorebird', 'Error checking for Shorebird updates: $e');
      return false;
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
