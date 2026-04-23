import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/helpers/data_persistence_helper.dart';

class ResponseHandler {
  final DataPersistenceHelper persistenceHelper;

  ResponseHandler({required this.persistenceHelper});

  Future<AuthResponse> handleLoginResponse(
    Map<String, dynamic> responseData,
    AuthState currentState,
    Function(AuthState)? updateState,
  ) async {
    if (_requiresOtp(responseData)) {
      updateState?.call(
        currentState.copyWith(
          isLoading: false,
          step: AuthStep.otpVerification,
          otpCode: responseData['otp_debug']?.toString(),
        ),
      );
      return AuthResponse(
        AuthEvent.requiresOtp,
        debugOtp: responseData['otp_debug']?.toString(),
      );
    }

    if (responseData['needsSchoolSelection'] == true) {
      return _handleSchoolSelection(responseData, currentState, updateState);
    }

    if (responseData['needsRoleSelection'] == true) {
      return _handleRoleSelection(responseData, currentState, updateState);
    }

    if (responseData['user'] == null) {
      updateState?.call(currentState.copyWith(isLoading: false));
      return AuthResponse(
        AuthEvent.error,
        messageMap: AppLocalizations.authIncompleteLoginData,
      );
    }

    await persistenceHelper.saveLoginData(responseData);
    updateState?.call(currentState.copyWith(isLoading: false));

    final user = User.fromJson(responseData['user']);
    final String userRole = user.role;
    if (userRole.isEmpty) {
      return AuthResponse(
        AuthEvent.error,
        messageMap: AppLocalizations.authUserRoleNotFound,
      );
    }

    return AuthResponse(AuthEvent.success, message: userRole);
  }

  bool _requiresOtp(Map<String, dynamic> responseData) {
    return responseData['require_otp'] == true ||
        responseData['otp_debug'] != null ||
        responseData['message'] == 'OTP sent to email';
  }

  Future<AuthResponse> _handleSchoolSelection(
    Map<String, dynamic> responseData,
    AuthState currentState,
    Function(AuthState)? updateState,
  ) async {
    if (responseData['sekolah_list'] == null ||
        (responseData['sekolah_list'] as List).isEmpty) {
      updateState?.call(currentState.copyWith(isLoading: false));
      return AuthResponse(
        AuthEvent.error,
        messageMap: AppLocalizations.authAccountNotRegisteredInAnySchool,
      );
    }

    if (responseData['token'] != null) {
      await _saveToken(responseData['token']);
    }

    updateState?.call(
      currentState.copyWith(
        step: AuthStep.schoolSelection,
        schoolList: responseData['sekolah_list'],
        userData: responseData['user'],
        isLoading: false,
      ),
    );
    return AuthResponse(AuthEvent.none);
  }

  Future<AuthResponse> _handleRoleSelection(
    Map<String, dynamic> responseData,
    AuthState currentState,
    Function(AuthState)? updateState,
  ) async {
    if (responseData['token'] != null) {
      await _saveToken(responseData['token']);
    }

    if (responseData['role_list'] == null ||
        (responseData['role_list'] as List).isEmpty) {
      updateState?.call(currentState.copyWith(isLoading: false));
      return AuthResponse(
        AuthEvent.error,
        messageMap: AppLocalizations.authRolesNotAvailable,
      );
    }

    updateState?.call(
      currentState.copyWith(
        step: AuthStep.roleSelection,
        roleList: responseData['role_list'],
        userData: responseData['user'],
        selectedSchool:
            responseData['school'] ??
            responseData['sekolah'] ??
            currentState.selectedSchool,
        isLoading: false,
      ),
    );
    return AuthResponse(AuthEvent.none);
  }

  Future<void> _saveToken(String token) async {
    final secureStorage = SecureStorageService();
    await secureStorage.saveToken(token);
    final prefs = PreferencesService();
    await prefs.setString('token', token);
  }
}
