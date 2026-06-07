import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/school_level_settings_screen.dart';

/// Mixin for data loading and API interactions.
mixin SchoolLevelDataMixin on State<SchoolLevelSettingsScreen> {
  /// Fetches school settings from API.
  /// Like calling `GET /api/settings/school` in Vue.
  Future<void> loadSchoolSettings({
    required Function(String) onSchoolNameChanged,
    required Function(String) onAddressChanged,
    required Function(String) onJenjangChanged,
    required Function(bool) onLoadingChanged,
  }) async {
    try {
      final settings = await getIt<ApiSettingsService>().getSchoolSettings();
      if (mounted) {
        setState(() {
          // Backend renamed `school_name`→`name`, `jenjang`→`education_level`.
          onSchoolNameChanged(
            (settings['name'] ?? settings['school_name'] ?? '').toString(),
          );
          onAddressChanged(settings['address'] ?? '');
          onJenjangChanged(
            (settings['education_level'] ?? settings['jenjang'] ?? 'SMA')
                .toString(),
          );
          onLoadingChanged(false);
        });
      }
    } catch (e) {
      AppLogger.error('settings', e);
      if (mounted) {
        setState(() => onLoadingChanged(false));
        SnackBarUtils.showError(
          context,
          '${kSetFailedLoadSettings.tr}${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  /// Updates school settings on the API.
  /// Like calling `PUT /api/settings/school` in Vue.
  Future<void> updateSchoolSettings({
    required String schoolName,
    required String address,
    required String jenjang,
  }) async {
    await getIt<ApiSettingsService>().updateSchoolSettings(
      schoolName: schoolName,
      address: address,
      jenjang: jenjang,
    );
  }
}
