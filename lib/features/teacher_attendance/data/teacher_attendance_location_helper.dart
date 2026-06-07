// teacher_attendance_location_helper.dart — wraps the geolocator plugin
// for the Presensi Guru check-in flow.
//
// Why a helper? geolocator's permission dance has three moving parts
// (is the OS location service even on? is permission granted? is it
// permanently denied so we must send the user to Settings?). Bundling
// it here keeps the screen readable and gives us a single typed result
// the UI can switch on — like a Laravel form-request that returns one
// clear validation outcome instead of scattering checks in the
// controller.
library;

import 'package:geolocator/geolocator.dart';

/// Outcome of a location fix attempt. The screen renders a tailored
/// message per case (turn on GPS, grant permission, open Settings).
enum LocationResultStatus {
  success,
  serviceDisabled, // device location/GPS toggle is off
  permissionDenied, // user tapped "deny" this time
  permissionDeniedForever, // "don't ask again" — must use app settings
  error,
}

/// A captured GPS fix plus the status that produced it.
class LocationResult {
  final LocationResultStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracy; // metres
  final String? errorMessage;

  const LocationResult({
    required this.status,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.errorMessage,
  });

  bool get isSuccess => status == LocationResultStatus.success;
}

/// Thin facade over geolocator for the teacher attendance flow.
class TeacherAttendanceLocationHelper {
  /// Requests permission as needed and returns the current GPS fix.
  ///
  /// Mirrors geolocator's recommended flow: confirm the service is on,
  /// then resolve permission (requesting it once if still undetermined),
  /// then read a single high-accuracy position. Any thrown error is
  /// captured into a [LocationResult] so the caller never has to
  /// try/catch the plugin directly.
  Future<LocationResult> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          status: LocationResultStatus.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          status: LocationResultStatus.permissionDeniedForever,
        );
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(
          status: LocationResultStatus.permissionDenied,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      return LocationResult(
        status: LocationResultStatus.success,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (e) {
      return LocationResult(
        status: LocationResultStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Opens the OS app-settings page so a user who picked "don't ask
  /// again" can re-enable location permission manually.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Opens the OS location-services settings so the user can flip the
  /// device GPS toggle back on.
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
